-- HR Fingerprint Transactions Schema
-- This table stores employee fingerprint punch records for attendance tracking

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
      (
        ARRAY[
          'Check In'::character varying,
          'Check Out'::character varying
        ]
      )::text[]
    )
  )
) TABLESPACE pg_default;

-- Indexes for performance optimization
CREATE INDEX IF NOT EXISTS idx_hr_fingerprint_employee_id ON public.hr_fingerprint_transactions USING btree (employee_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_fingerprint_date ON public.hr_fingerprint_transactions USING btree (transaction_date) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_fingerprint_punch_state ON public.hr_fingerprint_transactions USING btree (punch_state) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_fingerprint_branch_id ON public.hr_fingerprint_transactions USING btree (branch_id) TABLESPACE pg_default;