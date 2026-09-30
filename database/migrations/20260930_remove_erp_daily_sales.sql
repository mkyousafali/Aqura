begin;

drop table if exists public.erp_daily_sales;
drop function if exists public.notify_erp_daily_sales_change();
drop function if exists public.update_erp_daily_sales_updated_at();

commit;
