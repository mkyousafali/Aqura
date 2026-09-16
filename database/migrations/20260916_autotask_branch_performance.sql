begin;
create or replace function public."Autotask_get_branch_performance_dashboard"(p_requesting_user_id uuid,p_days_back integer default 30,p_specific_date date default null)
returns json language sql stable security definer set search_path=public as $$
with authorized as (
  select exists(select 1 from public.users u where u.id=p_requesting_user_id and u.status='active' and
    (coalesce(u.is_master_admin,false) or exists(select 1 from public.button_permissions bp where bp.user_id=u.id and bp.button_code='BRANCH_PERFORMANCE' and bp.is_enabled=true))) ok
), bounds as (
  select case when p_specific_date is null then now()-(p_days_back||' days')::interval else p_specific_date::timestamp end f,
         case when p_specific_date is null then now() else (p_specific_date+1)::timestamp end t from authorized where ok
), base as (select public.get_branch_performance_dashboard(p_days_back,p_specific_date)::jsonb j),
tasks as (
 select ta.assigned_to_user_id uid,e.current_branch_id::text bid,ta.status,ta.assigned_at created_at,ta.completed_at,
   case when ta.deadline_date is null then null else (ta.deadline_date::text||' '||coalesce(ta.deadline_time::text,'23:59:59'))::timestamptz end due_at,'regular' typ
 from task_assignments ta left join hr_employee_master e on e.user_id=ta.assigned_to_user_id,bounds x where ta.assigned_at>=x.f and ta.assigned_at<x.t
 union all select qta.assigned_to_user_id,e.current_branch_id::text,qta.status,qta.created_at,qta.completed_at,qt.deadline_datetime,'quick'
 from quick_task_assignments qta join quick_tasks qt on qt.id=qta.quick_task_id left join hr_employee_master e on e.user_id=qta.assigned_to_user_id,bounds x where qta.created_at>=x.f and qta.created_at<x.t
 union all select a.assignee_user_id,a.branch_id,a.status,a.created_at,a.completed_at,a.due_at,'auto'
 from "Autotask_tasks" a,bounds x where a.created_at>=x.f and a.created_at<x.t
), totals as (
 select jsonb_build_object('total_tasks',count(*),'completed_tasks',count(*) filter(where status='completed'),
 'pending_tasks',count(*) filter(where status not in('completed','cancelled')),
 'overdue_tasks',count(*) filter(where status not in('completed','cancelled') and due_at<now()),
 'avg_completion_hours',round(coalesce(avg(extract(epoch from(completed_at-created_at))/3600) filter(where status='completed'),0)::numeric,1),
 'auto_tasks',count(*) filter(where typ='auto')) j from tasks
), branch_rows as (
 select b.id branch_id,b.name_en branch_name_en,b.name_ar branch_name_ar,b.location_en branch_location_en,b.location_ar branch_location_ar,
 count(t.*) total_tasks,count(t.*) filter(where status='completed') completed,count(t.*) filter(where status not in('completed','cancelled')) pending,
 count(t.*) filter(where status not in('completed','cancelled') and due_at<now()) overdue,
 count(t.*) filter(where typ='regular') regular_count,count(t.*) filter(where typ='quick') quick_count,count(t.*) filter(where typ='receiving') receiving_count,
 count(t.*) filter(where typ='auto') auto_count,coalesce(cl.cnt,0) checklist_count,coalesce(cl.score,0) avg_checklist_score,
 case when count(t.*)>0 then round(count(t.*) filter(where status='completed')::numeric/count(t.*)*100,1) else 0 end completion_rate
 from branches b left join tasks t on t.bid=b.id::text left join lateral(select count(*) cnt,round(avg(c.total_points::numeric/nullif(c.max_points,0)*100),1) score from hr_checklist_operations c,bounds x where c.branch_id=b.id and c.created_at>=x.f and c.created_at<x.t)cl on true
 group by b.id,b.name_en,b.name_ar,b.location_en,b.location_ar,cl.cnt,cl.score having count(t.*)+coalesce(cl.cnt,0)>0
), employee_rows as (
 select t.uid,e.name_en,e.name_ar,b.name_en branch_name_en,b.name_ar branch_name_ar,count(*) total,count(*) filter(where t.status='completed') completed,
 case when count(*)>0 then round(count(*) filter(where t.status='completed')::numeric/count(*)*100,1) else 0 end rate,
 count(*) filter(where typ='auto') auto_count,coalesce(cl.cnt,0) checklist_count,coalesce(cl.score,0) avg_checklist_score
 from tasks t left join hr_employee_master e on e.user_id=t.uid left join branches b on b.id=e.current_branch_id
 left join lateral(select count(*) cnt,round(avg(c.total_points::numeric/nullif(c.max_points,0)*100),1) score from hr_checklist_operations c,bounds x where c.user_id=t.uid and c.created_at>=x.f and c.created_at<x.t)cl on true
 where t.uid is not null group by t.uid,e.name_en,e.name_ar,b.name_en,b.name_ar,cl.cnt,cl.score
), daily_rows as (
 select d::date day,count(t.*) filter(where t.created_at::date=d::date) created,count(t.*) filter(where t.status='completed' and t.completed_at::date=d::date) completed
 from bounds x,generate_series(x.f::date,least(x.t::date,current_date),'1 day')d left join tasks t on t.created_at::date=d::date or t.completed_at::date=d::date group by d::date
), assembled as (
 select (base.j||jsonb_build_object('totals',(totals.j||jsonb_build_object('total_checklists',base.j#>'{totals,total_checklists}','avg_checklist_score',base.j#>'{totals,avg_checklist_score}')),
 'branch_stats',coalesce((select jsonb_agg(to_jsonb(branch_rows) order by total_tasks desc) from branch_rows),'[]'::jsonb),
 'top_employees',coalesce((select jsonb_agg(to_jsonb(employee_rows) order by completed desc) from employee_rows),'[]'::jsonb),
 'daily_stats',coalesce((select jsonb_agg(to_jsonb(daily_rows) order by day) from daily_rows),'[]'::jsonb),
 'task_type_stats',(base.j->'task_type_stats')||jsonb_build_object('auto',(select count(*) from tasks where typ='auto')))) j from base,totals
) select assembled.j::json from assembled,authorized where authorized.ok
$$;
grant execute on function public."Autotask_get_branch_performance_dashboard"(uuid,integer,date) to anon,authenticated;
commit;
