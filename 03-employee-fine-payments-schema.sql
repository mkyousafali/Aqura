-- Employee Fine Payments Schema
-- Manages fine payments for employee warnings and violations

CREATE TABLE public.employee_fine_payments (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  warning_id uuid NULL,
  payment_method character varying(50) NULL,
  payment_amount numeric(10, 2) NOT NULL,
  payment_currency character varying(3) NULL DEFAULT 'USD'::character varying,
  payment_date timestamp without time zone NULL DEFAULT CURRENT_TIMESTAMP,
  payment_reference character varying(100) NULL,
  payment_notes text NULL,
  processed_by uuid NULL,
  processed_by_username character varying(255) NULL,
  account_code character varying(50) NULL,
  transaction_id character varying(100) NULL,
  receipt_number character varying(100) NULL,
  created_at timestamp without time zone NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp without time zone NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT employee_fine_payments_pkey PRIMARY KEY (id),
  CONSTRAINT employee_fine_payments_processed_by_fkey FOREIGN KEY (processed_by) REFERENCES users (id) ON DELETE SET NULL
) TABLESPACE pg_default;

-- Indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_fine_payments_warning_id ON public.employee_fine_payments USING btree (warning_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_fine_payments_payment_date ON public.employee_fine_payments USING btree (payment_date) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_fine_payments_processed_by ON public.employee_fine_payments USING btree (processed_by) TABLESPACE pg_default;