create table public.notification_attachments (
  id uuid not null default gen_random_uuid (),
  notification_id uuid not null,
  file_name character varying(255) not null,
  file_path text not null,
  file_size bigint not null,
  file_type character varying(100) not null,
  uploaded_by character varying(255) not null,
  created_at timestamp with time zone not null default now(),
  constraint notification_attachments_pkey primary key (id),
  constraint notification_attachments_notification_fkey foreign KEY (notification_id) references notifications (id) on delete CASCADE
) TABLESPACE pg_default;

create index IF not exists idx_notification_attachments_notification_id on public.notification_attachments using btree (notification_id) TABLESPACE pg_default;

create index IF not exists idx_notification_attachments_uploaded_by on public.notification_attachments using btree (uploaded_by) TABLESPACE pg_default;