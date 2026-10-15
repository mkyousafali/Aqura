begin;

update public.bank_payment_planner_schedule_items
set application_batch_id = md5(
  schedule_id::text || ':' || vendor_id || ':' || created_at::text
)::uuid
where application_batch_id = md5(schedule_id::text || ':' || vendor_id)::uuid;

notify pgrst, 'reload schema';
commit;
