-- Tasks Table Schema
CREATE TABLE IF NOT EXISTS tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title VARCHAR NOT NULL,
  description TEXT,
  require_task_finished BOOLEAN DEFAULT false,
  require_photo_upload BOOLEAN DEFAULT false,
  require_erp_reference BOOLEAN DEFAULT false,
  can_escalate BOOLEAN DEFAULT false,
  can_reassign BOOLEAN DEFAULT false,
  created_by TEXT NOT NULL,
  created_by_name TEXT,
  created_by_role TEXT,
  status TEXT DEFAULT 'draft',
  priority TEXT DEFAULT 'medium',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  deleted_at TIMESTAMP WITH TIME ZONE,
  due_date DATE,
  due_time TIME WITHOUT TIME ZONE,
  due_datetime TIMESTAMP WITH TIME ZONE,
  search_vector TSVECTOR,
  metadata JSONB
);
