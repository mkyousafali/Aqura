-- Migration: Create receiving_tasks table
-- File: 30_receiving_tasks.sql
-- Description: Creates the receiving_tasks table for managing task assignments related to receiving records

BEGIN;

-- Create trigger function for receiving tasks
CREATE OR REPLACE FUNCTION update_receiving_tasks_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create receiving_tasks table
CREATE TABLE public.receiving_tasks (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  receiving_record_id uuid NOT NULL,
  task_id uuid NOT NULL,
  assignment_id uuid NOT NULL,
  role_type character varying(50) NOT NULL,
  assigned_user_id uuid NULL,
  requires_erp_reference boolean NULL DEFAULT false,
  requires_original_bill_upload boolean NULL DEFAULT false,
  requires_reassignment boolean NULL DEFAULT false,
  requires_task_finished_mark boolean NULL DEFAULT true,
  erp_reference_number character varying(255) NULL,
  original_bill_uploaded boolean NULL DEFAULT false,
  original_bill_file_path text NULL,
  task_completed boolean NULL DEFAULT false,
  completed_at timestamp with time zone NULL,
  clearance_certificate_url text NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT receiving_tasks_pkey PRIMARY KEY (id),
  CONSTRAINT receiving_tasks_assigned_user_id_fkey FOREIGN KEY (assigned_user_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT receiving_tasks_assignment_id_fkey FOREIGN KEY (assignment_id) REFERENCES task_assignments (id) ON DELETE CASCADE,
  CONSTRAINT receiving_tasks_receiving_record_id_fkey FOREIGN KEY (receiving_record_id) REFERENCES receiving_records (id) ON DELETE CASCADE,
  CONSTRAINT receiving_tasks_task_id_fkey FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE,
  CONSTRAINT receiving_tasks_role_type_check CHECK (
    (
      (role_type)::text = ANY (
        ARRAY[
          ('branch_manager'::character varying)::text,
          ('purchase_manager'::character varying)::text,
          ('inventory_manager'::character varying)::text,
          ('night_supervisor'::character varying)::text,
          ('warehouse_handler'::character varying)::text,
          ('shelf_stocker'::character varying)::text,
          ('accountant'::character varying)::text
        ]
      )
    )
  )
) TABLESPACE pg_default;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_receiving_tasks_receiving_record_id 
ON public.receiving_tasks USING btree (receiving_record_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_tasks_task_id 
ON public.receiving_tasks USING btree (task_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_tasks_assignment_id 
ON public.receiving_tasks USING btree (assignment_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_tasks_assigned_user_id 
ON public.receiving_tasks USING btree (assigned_user_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_tasks_role_type 
ON public.receiving_tasks USING btree (role_type) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_tasks_task_completed 
ON public.receiving_tasks USING btree (task_completed) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_tasks_created_at 
ON public.receiving_tasks USING btree (created_at DESC) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_tasks_user_role 
ON public.receiving_tasks USING btree (assigned_user_id, role_type) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_tasks_record_role 
ON public.receiving_tasks USING btree (receiving_record_id, role_type) 
TABLESPACE pg_default;

-- Create trigger
CREATE TRIGGER trigger_update_receiving_tasks_updated_at 
BEFORE UPDATE ON receiving_tasks 
FOR EACH ROW
EXECUTE FUNCTION update_receiving_tasks_updated_at();

COMMIT;