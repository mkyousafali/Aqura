-- HR Position Reporting Template Table Schema
CREATE TABLE IF NOT EXISTS hr_position_reporting_template (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  subordinate_position_id UUID NOT NULL,
  manager_position_1 UUID,
  manager_position_2 UUID,
  manager_position_3 UUID,
  manager_position_4 UUID,
  manager_position_5 UUID,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
