create table public.hr_position_reporting_template (
  id uuid not null default extensions.uuid_generate_v4 (),
  subordinate_position_id uuid not null,
  manager_position_1 uuid null,
  manager_position_2 uuid null,
  manager_position_3 uuid null,
  manager_position_4 uuid null,
  manager_position_5 uuid null,
  is_active boolean null default true,
  created_at timestamp with time zone null default now(),
  constraint hr_position_reporting_template_pkey primary key (id),
  constraint hr_position_reporting_template_subordinate_position_id_key unique (subordinate_position_id),
  constraint hr_position_reporting_template_manager_position_2_fkey foreign KEY (manager_position_2) references hr_positions (id),
  constraint hr_position_reporting_template_manager_position_1_fkey foreign KEY (manager_position_1) references hr_positions (id),
  constraint hr_position_reporting_template_manager_position_3_fkey foreign KEY (manager_position_3) references hr_positions (id),
  constraint hr_position_reporting_template_manager_position_4_fkey foreign KEY (manager_position_4) references hr_positions (id),
  constraint hr_position_reporting_template_manager_position_5_fkey foreign KEY (manager_position_5) references hr_positions (id),
  constraint hr_position_reporting_template_subordinate_position_id_fkey foreign KEY (subordinate_position_id) references hr_positions (id),
  constraint chk_no_self_report_4 check ((subordinate_position_id <> manager_position_4)),
  constraint chk_no_self_report_5 check ((subordinate_position_id <> manager_position_5)),
  constraint chk_no_self_report_3 check ((subordinate_position_id <> manager_position_3)),
  constraint chk_no_self_report_1 check ((subordinate_position_id <> manager_position_1)),
  constraint chk_no_self_report_2 check ((subordinate_position_id <> manager_position_2))
) TABLESPACE pg_default;

create index IF not exists idx_hr_position_template_subordinate on public.hr_position_reporting_template using btree (subordinate_position_id) TABLESPACE pg_default;

create index IF not exists idx_hr_position_template_mgr1 on public.hr_position_reporting_template using btree (manager_position_1) TABLESPACE pg_default;

create index IF not exists idx_hr_position_template_mgr2 on public.hr_position_reporting_template using btree (manager_position_2) TABLESPACE pg_default;

create index IF not exists idx_hr_position_template_mgr3 on public.hr_position_reporting_template using btree (manager_position_3) TABLESPACE pg_default;

create index IF not exists idx_hr_position_template_mgr4 on public.hr_position_reporting_template using btree (manager_position_4) TABLESPACE pg_default;

create index IF not exists idx_hr_position_template_mgr5 on public.hr_position_reporting_template using btree (manager_position_5) TABLESPACE pg_default;