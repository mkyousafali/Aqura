begin;

create or replace function public.mark_pay_to_credit_transaction_posted()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'completed'
     and old.status is distinct from new.status
     and new.task_type in ('receiving_bank_payment', 'receiving_cash_payment')
     and new.payload ? 'pay_to_credit_transaction_id'
  then
    update public.pos_scan_requests
       set status = 'posted',
           updated_at = now()
     where id = new.source_record_id
       and request_type = 'pay_to_credit_slip';
  end if;

  return new;
end;
$$;

drop trigger if exists assistant_task_hide_posted_pay_to_credit
  on public.assistant_workflow_tasks;

create trigger assistant_task_hide_posted_pay_to_credit
after update of status on public.assistant_workflow_tasks
for each row
execute function public.mark_pay_to_credit_transaction_posted();

update public.pos_scan_requests as scan
   set status = 'posted',
       updated_at = now()
 where scan.request_type = 'pay_to_credit_slip'
   and scan.status = 'completed'
   and exists (
     select 1
       from public.assistant_workflow_tasks as task
      where task.source_record_id = scan.id
        and task.task_type in ('receiving_bank_payment', 'receiving_cash_payment')
        and task.status = 'completed'
        and task.payload ? 'pay_to_credit_transaction_id'
   );

commit;
