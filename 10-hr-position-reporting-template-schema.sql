-- Table 10: HR Position Reporting Template
-- Purpose: Defines hierarchical reporting structure template for positions
-- Created: 2025-09-29

CREATE TABLE public.hr_position_reporting_template (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  subordinate_position_id uuid NOT NULL,
  manager_position_1 uuid NULL,
  manager_position_2 uuid NULL,
  manager_position_3 uuid NULL,
  manager_position_4 uuid NULL,
  manager_position_5 uuid NULL,
  is_active boolean NULL DEFAULT true,
  created_at timestamp with time zone NULL DEFAULT now(),
  CONSTRAINT hr_position_reporting_template_pkey PRIMARY KEY (id),
  CONSTRAINT hr_position_reporting_template_subordinate_position_id_key UNIQUE (subordinate_position_id),
  CONSTRAINT hr_position_reporting_template_manager_position_1_fkey FOREIGN KEY (manager_position_1) REFERENCES hr_positions (id),
  CONSTRAINT hr_position_reporting_template_manager_position_2_fkey FOREIGN KEY (manager_position_2) REFERENCES hr_positions (id),
  CONSTRAINT hr_position_reporting_template_manager_position_3_fkey FOREIGN KEY (manager_position_3) REFERENCES hr_positions (id),
  CONSTRAINT hr_position_reporting_template_manager_position_4_fkey FOREIGN KEY (manager_position_4) REFERENCES hr_positions (id),
  CONSTRAINT hr_position_reporting_template_manager_position_5_fkey FOREIGN KEY (manager_position_5) REFERENCES hr_positions (id),
  CONSTRAINT hr_position_reporting_template_subordinate_position_id_fkey FOREIGN KEY (subordinate_position_id) REFERENCES hr_positions (id),
  CONSTRAINT chk_no_self_report_1 CHECK ((subordinate_position_id <> manager_position_1)),
  CONSTRAINT chk_no_self_report_2 CHECK ((subordinate_position_id <> manager_position_2)),
  CONSTRAINT chk_no_self_report_3 CHECK ((subordinate_position_id <> manager_position_3)),
  CONSTRAINT chk_no_self_report_4 CHECK ((subordinate_position_id <> manager_position_4)),
  CONSTRAINT chk_no_self_report_5 CHECK ((subordinate_position_id <> manager_position_5))
) TABLESPACE pg_default;

-- Indexes for better performance
CREATE INDEX IF NOT EXISTS idx_hr_position_template_subordinate 
  ON public.hr_position_reporting_template USING btree (subordinate_position_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_position_template_mgr1 
  ON public.hr_position_reporting_template USING btree (manager_position_1) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_position_template_mgr2 
  ON public.hr_position_reporting_template USING btree (manager_position_2) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_position_template_mgr3 
  ON public.hr_position_reporting_template USING btree (manager_position_3) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_position_template_mgr4 
  ON public.hr_position_reporting_template USING btree (manager_position_4) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_position_template_mgr5 
  ON public.hr_position_reporting_template USING btree (manager_position_5) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_position_template_active 
  ON public.hr_position_reporting_template USING btree (is_active) TABLESPACE pg_default;

-- Comments for documentation
COMMENT ON TABLE public.hr_position_reporting_template IS 'Defines hierarchical reporting structure template with up to 5 management levels';
COMMENT ON COLUMN public.hr_position_reporting_template.id IS 'Primary key - UUID generated automatically';
COMMENT ON COLUMN public.hr_position_reporting_template.subordinate_position_id IS 'Position that reports to managers (unique, references hr_positions)';
COMMENT ON COLUMN public.hr_position_reporting_template.manager_position_1 IS 'Direct manager position (Level 1) - references hr_positions';
COMMENT ON COLUMN public.hr_position_reporting_template.manager_position_2 IS 'Second level manager position - references hr_positions';
COMMENT ON COLUMN public.hr_position_reporting_template.manager_position_3 IS 'Third level manager position - references hr_positions';
COMMENT ON COLUMN public.hr_position_reporting_template.manager_position_4 IS 'Fourth level manager position - references hr_positions';
COMMENT ON COLUMN public.hr_position_reporting_template.manager_position_5 IS 'Fifth level manager position - references hr_positions';
COMMENT ON COLUMN public.hr_position_reporting_template.is_active IS 'Whether this reporting template is currently active';
COMMENT ON COLUMN public.hr_position_reporting_template.created_at IS 'Timestamp when the record was created';