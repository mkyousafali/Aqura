-- PostgreSQL LISTEN/NOTIFY trigger for erp_daily_sales table
-- This enables automatic cache invalidation when sales data changes

-- Function that sends notification when erp_daily_sales changes
CREATE OR REPLACE FUNCTION notify_erp_daily_sales_change() 
RETURNS trigger AS $$
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
$$ LANGUAGE plpgsql;

-- Trigger on INSERT, UPDATE, DELETE
DROP TRIGGER IF EXISTS erp_daily_sales_notify_trigger ON erp_daily_sales;
CREATE TRIGGER erp_daily_sales_notify_trigger
AFTER INSERT OR UPDATE OR DELETE ON erp_daily_sales
FOR EACH ROW EXECUTE FUNCTION notify_erp_daily_sales_change();

-- Verify trigger was created
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE trigger_name = 'erp_daily_sales_notify_trigger';
