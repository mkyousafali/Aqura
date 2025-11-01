create table public.hr_employee_contacts (
  id uuid not null default extensions.uuid_generate_v4 (),
  employee_id uuid not null,
  email character varying(100) null,
  is_active boolean null default true,
  created_at timestamp with time zone null default now(),
  whatsapp_number character varying(20) null,
  contact_number character varying(20) null,
  constraint hr_employee_contacts_pkey primary key (id),
  constraint hr_employee_contacts_employee_id_fkey foreign KEY (employee_id) references hr_employees (id)
) TABLESPACE pg_default;

create index IF not exists idx_hr_contacts_employee_id on public.hr_employee_contacts using btree (employee_id) TABLESPACE pg_default;