-- =====================================================
-- RECEIVING TASK TEMPLATES TABLE
-- =====================================================
-- Purpose: Store reusable task templates for receiving workflow
-- Each template defines a task type for a specific role
-- Used by process_clearance_certificate_generation() function
-- =====================================================

-- Drop existing table if it exists to allow recreation with new structure
DROP TABLE IF EXISTS public.receiving_task_templates CASCADE;

CREATE TABLE public.receiving_task_templates (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  role_type VARCHAR(50) NOT NULL,
  title_template TEXT NOT NULL,
  description_template TEXT NOT NULL,
  require_erp_reference BOOLEAN NOT NULL DEFAULT false,
  require_original_bill_upload BOOLEAN NOT NULL DEFAULT false,
  require_task_finished_mark BOOLEAN NOT NULL DEFAULT true,
  priority VARCHAR(20) NOT NULL DEFAULT 'high',
  deadline_hours INTEGER NOT NULL DEFAULT 24,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  
  CONSTRAINT receiving_task_templates_pkey PRIMARY KEY (id),
  CONSTRAINT receiving_task_templates_role_type_unique UNIQUE (role_type),
  CONSTRAINT receiving_task_templates_role_type_check CHECK (
    role_type IN (
      'branch_manager',
      'purchase_manager',
      'inventory_manager',
      'night_supervisor',
      'warehouse_handler',
      'shelf_stocker',
      'accountant'
    )
  ),
  CONSTRAINT receiving_task_templates_priority_check CHECK (
    priority IN ('low', 'medium', 'high', 'urgent')
  ),
  CONSTRAINT receiving_task_templates_deadline_hours_check CHECK (
    deadline_hours > 0 AND deadline_hours <= 168
  )
) TABLESPACE pg_default;

-- =====================================================
-- INDEXES
-- =====================================================

CREATE INDEX idx_receiving_task_templates_role_type 
  ON public.receiving_task_templates USING btree (role_type) 
  TABLESPACE pg_default;

CREATE INDEX idx_receiving_task_templates_priority 
  ON public.receiving_task_templates USING btree (priority) 
  TABLESPACE pg_default;

-- =====================================================
-- TRIGGER FOR UPDATED_AT
-- =====================================================

CREATE OR REPLACE FUNCTION update_receiving_task_templates_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_receiving_task_templates_updated_at
  BEFORE UPDATE ON receiving_task_templates
  FOR EACH ROW
  EXECUTE FUNCTION update_receiving_task_templates_updated_at();

-- =====================================================
-- COMMENTS
-- =====================================================

COMMENT ON TABLE public.receiving_task_templates IS 
  'Reusable task templates for receiving workflow. Each role has one template.';

COMMENT ON COLUMN public.receiving_task_templates.role_type IS 
  'Role type: branch_manager, purchase_manager, inventory_manager, night_supervisor, warehouse_handler, shelf_stocker, accountant';

COMMENT ON COLUMN public.receiving_task_templates.title_template IS 
  'Task title template. Use {placeholders} for dynamic content.';

COMMENT ON COLUMN public.receiving_task_templates.description_template IS 
  'Task description template. Use {placeholders} for branch, vendor, bill details.';
