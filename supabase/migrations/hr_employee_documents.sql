create table public.hr_employee_documents (
  id uuid not null default extensions.uuid_generate_v4 (),
  employee_id uuid not null,
  document_type character varying(50) not null,
  document_name character varying(200) not null,
  file_path text not null,
  file_type character varying(50) null,
  expiry_date date null,
  upload_date date not null default CURRENT_DATE,
  is_active boolean not null default true,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone null default now(),
  document_number character varying(100) null,
  document_description text null,
  health_card_number character varying(100) null,
  health_card_expiry date null,
  resident_id_number character varying(100) null,
  resident_id_expiry date null,
  passport_number character varying(100) null,
  passport_expiry date null,
  driving_license_number character varying(100) null,
  driving_license_expiry date null,
  resume_uploaded boolean null default false,
  document_category public.document_category_enum null default 'other'::document_category_enum,
  category_start_date date null,
  category_end_date date null,
  category_days integer null,
  category_last_working_day date null,
  category_reason text null,
  category_details text null,
  category_content text null,
  constraint hr_employee_documents_pkey primary key (id),
  constraint hr_employee_documents_employee_id_fkey foreign KEY (employee_id) references hr_employees (id) on delete CASCADE,
  constraint check_leave_dates check (
    (
      (
        document_category <> all (
          array[
            'sick_leave'::document_category_enum,
            'special_leave'::document_category_enum,
            'annual_leave'::document_category_enum
          ]
        )
      )
      or (
        (category_start_date is null)
        or (category_end_date is null)
        or (category_start_date <= category_end_date)
      )
    )
  ),
  constraint check_resignation_last_working_day check (
    (
      (
        document_category <> 'resignation'::document_category_enum
      )
      or (category_last_working_day is not null)
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_hr_documents_document_number on public.hr_employee_documents using btree (document_number) TABLESPACE pg_default
where
  (document_number is not null);

create index IF not exists idx_hr_documents_employee_id on public.hr_employee_documents using btree (employee_id) TABLESPACE pg_default;

create index IF not exists idx_hr_documents_type on public.hr_employee_documents using btree (document_type) TABLESPACE pg_default;

create index IF not exists idx_hr_documents_expiry on public.hr_employee_documents using btree (expiry_date) TABLESPACE pg_default;

create index IF not exists idx_hr_documents_active on public.hr_employee_documents using btree (is_active) TABLESPACE pg_default;

create index IF not exists idx_hr_documents_health_card_number on public.hr_employee_documents using btree (health_card_number) TABLESPACE pg_default
where
  (health_card_number is not null);

create index IF not exists idx_hr_documents_resident_id_number on public.hr_employee_documents using btree (resident_id_number) TABLESPACE pg_default
where
  (resident_id_number is not null);

create index IF not exists idx_hr_documents_passport_number on public.hr_employee_documents using btree (passport_number) TABLESPACE pg_default
where
  (passport_number is not null);

create index IF not exists idx_hr_documents_driving_license_number on public.hr_employee_documents using btree (driving_license_number) TABLESPACE pg_default
where
  (driving_license_number is not null);

create index IF not exists idx_hr_documents_health_card_expiry on public.hr_employee_documents using btree (health_card_expiry) TABLESPACE pg_default
where
  (health_card_expiry is not null);

create index IF not exists idx_hr_documents_resident_id_expiry on public.hr_employee_documents using btree (resident_id_expiry) TABLESPACE pg_default
where
  (resident_id_expiry is not null);

create index IF not exists idx_hr_documents_passport_expiry on public.hr_employee_documents using btree (passport_expiry) TABLESPACE pg_default
where
  (passport_expiry is not null);

create index IF not exists idx_hr_documents_driving_license_expiry on public.hr_employee_documents using btree (driving_license_expiry) TABLESPACE pg_default
where
  (driving_license_expiry is not null);

create index IF not exists idx_hr_employee_documents_category on public.hr_employee_documents using btree (document_category) TABLESPACE pg_default;

create index IF not exists idx_hr_employee_documents_category_dates on public.hr_employee_documents using btree (
  document_category,
  category_start_date,
  category_end_date
) TABLESPACE pg_default
where
  (category_start_date is not null);

create trigger trigger_calculate_category_days BEFORE INSERT
or
update on hr_employee_documents for EACH row
execute FUNCTION calculate_category_days ();

create trigger trigger_clear_main_document_columns BEFORE DELETE on hr_employee_documents for EACH row
execute FUNCTION clear_main_document_columns ();

create trigger trigger_handle_document_deactivation BEFORE
update on hr_employee_documents for EACH row
execute FUNCTION handle_document_deactivation ();

create trigger trigger_update_main_document_columns BEFORE INSERT
or
update on hr_employee_documents for EACH row
execute FUNCTION update_main_document_columns ();