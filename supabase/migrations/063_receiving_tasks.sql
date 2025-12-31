-- Receiving Tasks Table Schema
CREATE TABLE IF NOT EXISTS receiving_tasks (
  id INTEGER PRIMARY KEY DEFAULT nextval('receiving_tasks_id_seq'),
  purchase_order_id INTEGER NOT NULL,
  task_number VARCHAR UNIQUE,
  task_status VARCHAR NOT NULL DEFAULT 'pending',
  assigned_to UUID,
  expected_arrival_date TIMESTAMP WITH TIME ZONE,
  received_date TIMESTAMP WITH TIME ZONE,
  items_received JSONB,
  quality_notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
