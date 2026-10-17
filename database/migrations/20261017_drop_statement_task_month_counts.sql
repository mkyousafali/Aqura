begin;
drop function if exists public.get_statement_task_month_counts(date);
notify pgrst, 'reload schema';
commit;
