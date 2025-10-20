-- Migration: Create employee_warnings table
-- File: 5_employee_warnings.sql
-- Description: Creates the employee_warnings table for managing employee warnings and fines

BEGIN;

-- Create trigger functions that will be needed
CREATE OR REPLACE FUNCTION create_warning_history()
RETURNS TRIGGER AS $$
BEGIN
    -- This function will be implemented when needed
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION generate_warning_reference()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.warning_reference IS NULL THEN
        NEW.warning_reference := 'WRN-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(nextval('warning_ref_seq')::text, 6, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sync_fine_paid_columns()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.fine_paid_date IS NOT NULL AND OLD.fine_paid_date IS NULL THEN
        NEW.fine_paid_at := NEW.fine_paid_date;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_warning_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create sequence for warning reference
CREATE SEQUENCE IF NOT EXISTS warning_ref_seq START 1;

-- Create employee_warnings table
CREATE TABLE public.employee_warnings (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  user_id uuid NULL,
  employee_id uuid NULL,
  username character varying(255) NULL,
  warning_type character varying(50) NOT NULL,
  has_fine boolean NULL DEFAULT false,
  fine_amount numeric(10, 2) NULL DEFAULT NULL::numeric,
  fine_currency character varying(3) NULL DEFAULT 'USD'::character varying,
  fine_status character varying(20) NULL DEFAULT 'pending'::character varying,
  fine_due_date date NULL,
  fine_paid_date timestamp without time zone NULL,
  fine_paid_amount numeric(10, 2) NULL DEFAULT NULL::numeric,
  warning_text text NOT NULL,
  language_code character varying(5) NOT NULL DEFAULT 'en'::character varying,
  task_id uuid NULL,
  task_title character varying(500) NULL,
  task_description text NULL,
  assignment_id uuid NULL,
  total_tasks_assigned integer NULL DEFAULT 0,
  total_tasks_completed integer NULL DEFAULT 0,
  total_tasks_overdue integer NULL DEFAULT 0,
  completion_rate numeric(5, 2) NULL DEFAULT 0,
  issued_by uuid NULL,
  issued_by_username character varying(255) NULL,
  issued_at timestamp without time zone NULL DEFAULT CURRENT_TIMESTAMP,
  warning_status character varying(20) NULL DEFAULT 'active'::character varying,
  acknowledged_at timestamp without time zone NULL,
  acknowledged_by uuid NULL,
  resolved_at timestamp without time zone NULL,
  resolved_by uuid NULL,
  resolution_notes text NULL,
  created_at timestamp without time zone NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp without time zone NULL DEFAULT CURRENT_TIMESTAMP,
  branch_id bigint NULL,
  department_id uuid NULL,
  severity_level character varying(10) NULL DEFAULT 'medium'::character varying,
  follow_up_required boolean NULL DEFAULT false,
  follow_up_date date NULL,
  warning_reference character varying(50) NULL,
  warning_document_url text NULL,
  is_deleted boolean NULL DEFAULT false,
  deleted_at timestamp without time zone NULL,
  deleted_by uuid NULL,
  fine_paid_at timestamp without time zone NULL,
  frontend_save_id character varying(50) NULL,
  fine_payment_note text NULL,
  fine_payment_method character varying(50) NULL DEFAULT 'cash'::character varying,
  fine_payment_reference character varying(100) NULL,
  CONSTRAINT employee_warnings_pkey PRIMARY KEY (id),
  CONSTRAINT employee_warnings_warning_reference_key UNIQUE (warning_reference),
  CONSTRAINT employee_warnings_deleted_by_fkey FOREIGN KEY (deleted_by) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT employee_warnings_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES hr_employees (id) ON DELETE SET NULL,
  CONSTRAINT employee_warnings_issued_by_fkey FOREIGN KEY (issued_by) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT employee_warnings_resolved_by_fkey FOREIGN KEY (resolved_by) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT employee_warnings_acknowledged_by_fkey FOREIGN KEY (acknowledged_by) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT employee_warnings_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES branches (id) ON DELETE SET NULL,
  CONSTRAINT employee_warnings_user_id_fkey FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT employee_warnings_warning_type_check CHECK (
    (
      (warning_type)::text = ANY (
        ARRAY[
          ('overall_performance_no_fine'::character varying)::text,
          (
            'overall_performance_fine_threat'::character varying
          )::text,
          (
            'overall_performance_with_fine'::character varying
          )::text,
          ('task_specific_no_fine'::character varying)::text,
          ('task_specific_fine_threat'::character varying)::text,
          ('task_specific_with_fine'::character varying)::text
        ]
      )
    )
  ),
  CONSTRAINT employee_warnings_fine_status_check CHECK (
    (
      (fine_status)::text = ANY (
        ARRAY[
          ('pending'::character varying)::text,
          ('paid'::character varying)::text,
          ('waived'::character varying)::text,
          ('cancelled'::character varying)::text
        ]
      )
    )
  ),
  CONSTRAINT employee_warnings_warning_status_check CHECK (
    (
      (warning_status)::text = ANY (
        ARRAY[
          ('active'::character varying)::text,
          ('acknowledged'::character varying)::text,
          ('resolved'::character varying)::text,
          ('escalated'::character varying)::text,
          ('cancelled'::character varying)::text
        ]
      )
    )
  ),
  CONSTRAINT employee_warnings_severity_level_check CHECK (
    (
      (severity_level)::text = ANY (
        ARRAY[
          ('low'::character varying)::text,
          ('medium'::character varying)::text,
          ('high'::character varying)::text,
          ('critical'::character varying)::text
        ]
      )
    )
  )
) TABLESPACE pg_default;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_employee_warnings_user_id 
ON public.employee_warnings USING btree (user_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_employee_warnings_employee_id 
ON public.employee_warnings USING btree (employee_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_employee_warnings_username 
ON public.employee_warnings USING btree (username) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_employee_warnings_warning_type 
ON public.employee_warnings USING btree (warning_type) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_employee_warnings_warning_status 
ON public.employee_warnings USING btree (warning_status) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_employee_warnings_has_fine 
ON public.employee_warnings USING btree (has_fine) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_employee_warnings_fine_status 
ON public.employee_warnings USING btree (fine_status) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_employee_warnings_issued_at 
ON public.employee_warnings USING btree (issued_at) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_employee_warnings_task_id 
ON public.employee_warnings USING btree (task_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_employee_warnings_assignment_id 
ON public.employee_warnings USING btree (assignment_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_employee_warnings_branch_id 
ON public.employee_warnings USING btree (branch_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_employee_warnings_reference 
ON public.employee_warnings USING btree (warning_reference) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_employee_warnings_deleted 
ON public.employee_warnings USING btree (is_deleted) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_employee_warnings_issued_by 
ON public.employee_warnings USING btree (issued_by) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_employee_warnings_severity 
ON public.employee_warnings USING btree (severity_level) 
TABLESPACE pg_default;

CREATE UNIQUE INDEX IF NOT EXISTS idx_employee_warnings_reference_unique 
ON public.employee_warnings USING btree (warning_reference) 
TABLESPACE pg_default
WHERE (warning_reference IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_employee_warnings_user_type_date 
ON public.employee_warnings USING btree (user_id, warning_type, issued_at) 
TABLESPACE pg_default;

-- Create triggers
CREATE TRIGGER trigger_create_warning_history
AFTER INSERT OR DELETE OR UPDATE ON employee_warnings 
FOR EACH ROW
EXECUTE FUNCTION create_warning_history();

CREATE TRIGGER trigger_generate_warning_reference 
BEFORE INSERT ON employee_warnings 
FOR EACH ROW
EXECUTE FUNCTION generate_warning_reference();

CREATE TRIGGER trigger_sync_fine_paid_columns 
BEFORE INSERT OR UPDATE ON employee_warnings 
FOR EACH ROW
EXECUTE FUNCTION sync_fine_paid_columns();

CREATE TRIGGER trigger_update_warning_updated_at 
BEFORE UPDATE ON employee_warnings 
FOR EACH ROW
EXECUTE FUNCTION update_warning_updated_at();

COMMIT;