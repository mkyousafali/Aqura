create table public.hr_positions (
  id uuid not null default extensions.uuid_generate_v4 (),
  position_title_en character varying(100) not null,
  position_title_ar character varying(100) not null,
  department_id uuid not null,
  level_id uuid not null,
  is_active boolean null default true,
  created_at timestamp with time zone null default now(),
  constraint hr_positions_pkey primary key (id),
  constraint hr_positions_department_id_fkey foreign KEY (department_id) references hr_departments (id),
  constraint hr_positions_level_id_fkey foreign KEY (level_id) references hr_levels (id)
) TABLESPACE pg_default;

create trigger sync_roles_on_position_changes
after INSERT
or DELETE
or
update on hr_positions for EACH row
execute FUNCTION sync_user_roles_from_positions ();