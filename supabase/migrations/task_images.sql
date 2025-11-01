create table public.task_images (
  id uuid not null default gen_random_uuid (),
  task_id uuid not null,
  file_name text not null,
  file_size bigint not null,
  file_type text not null,
  file_url text not null,
  image_type text not null,
  uploaded_by text not null,
  uploaded_by_name text null,
  created_at timestamp with time zone null default now(),
  image_width integer null,
  image_height integer null,
  file_path text null,
  attachment_type text null default 'task_creation'::text,
  constraint task_images_pkey primary key (id),
  constraint task_images_task_id_fkey foreign KEY (task_id) references tasks (id) on delete CASCADE,
  constraint task_images_attachment_type_check check (
    (
      attachment_type = any (
        array['task_creation'::text, 'task_completion'::text]
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_task_images_task_id on public.task_images using btree (task_id) TABLESPACE pg_default;

create index IF not exists idx_task_images_uploaded_by on public.task_images using btree (uploaded_by) TABLESPACE pg_default;

create index IF not exists idx_task_images_image_type on public.task_images using btree (image_type) TABLESPACE pg_default;

create index IF not exists idx_task_images_attachment_type on public.task_images using btree (attachment_type) TABLESPACE pg_default;