-- Table 7: HR Fingerprint Transactions
-- Purpose: Manages employee fingerprint check-in/check-out transactions
-- Created: 2025-09-29

CREATE TABLE public.hr_fingerprint_transactions (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  employee_id character varying(10) NOT NULL,
  name character varying(200) NULL,
  branch_id bigint NOT NULL,
  transaction_date date NOT NULL,
  transaction_time time without time zone NOT NULL,
  punch_state character varying(20) NOT NULL,
  device_id character varying(50) NULL,
  created_at timestamp with time zone NULL DEFAULT now(),
  CONSTRAINT hr_fingerprint_transactions_pkey PRIMARY KEY (id),
  CONSTRAINT hr_fingerprint_transactions_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES branches (id),
  CONSTRAINT chk_hr_fingerprint_punch CHECK (
    (punch_state)::text = ANY (
      (ARRAY[
        'Check In'::character varying,
        'Check Out'::character varying
      ])::text[]
    )
  )
) TABLESPACE pg_default;

-- Indexes for better performance
CREATE INDEX IF NOT EXISTS idx_hr_fingerprint_employee_id 
  ON public.hr_fingerprint_transactions USING btree (employee_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_fingerprint_date 
  ON public.hr_fingerprint_transactions USING btree (transaction_date) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_fingerprint_punch_state 
  ON public.hr_fingerprint_transactions USING btree (punch_state) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_fingerprint_branch_id 
  ON public.hr_fingerprint_transactions USING btree (branch_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_fingerprint_datetime 
  ON public.hr_fingerprint_transactions USING btree (transaction_date, transaction_time) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_fingerprint_employee_date 
  ON public.hr_fingerprint_transactions USING btree (employee_id, transaction_date) TABLESPACE pg_default;

-- Comments for documentation
COMMENT ON TABLE public.hr_fingerprint_transactions IS 'Employee fingerprint attendance transactions with check-in/check-out tracking';
COMMENT ON COLUMN public.hr_fingerprint_transactions.id IS 'Primary key - UUID generated automatically';
COMMENT ON COLUMN public.hr_fingerprint_transactions.employee_id IS 'Employee identifier (10 chars max) - references hr_employees';
COMMENT ON COLUMN public.hr_fingerprint_transactions.name IS 'Employee name (optional, for display purposes)';
COMMENT ON COLUMN public.hr_fingerprint_transactions.branch_id IS 'Foreign key reference to branches table (required)';
COMMENT ON COLUMN public.hr_fingerprint_transactions.transaction_date IS 'Date of the fingerprint transaction (required)';
COMMENT ON COLUMN public.hr_fingerprint_transactions.transaction_time IS 'Time of the fingerprint transaction (required)';
COMMENT ON COLUMN public.hr_fingerprint_transactions.punch_state IS 'Type of punch: Check In or Check Out (required, constrained)';
COMMENT ON COLUMN public.hr_fingerprint_transactions.device_id IS 'Identifier of the fingerprint device used (optional)';
COMMENT ON COLUMN public.hr_fingerprint_transactions.created_at IS 'Timestamp when the record was created';