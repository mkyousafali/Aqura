-- Create warning system tables
-- These tables store warning categories, subcategories, and violations for HR management

-- 1. Warning Main Category Table
CREATE TABLE IF NOT EXISTS warning_main_category (
  id VARCHAR(10) PRIMARY KEY,  -- wam1, wam2, etc.
  name_en VARCHAR(255) NOT NULL,
  name_ar VARCHAR(255) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_warning_main_category_name_en ON warning_main_category(name_en);

-- Create auto-update trigger for updated_at
CREATE OR REPLACE FUNCTION update_warning_main_category_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER warning_main_category_timestamp_update
BEFORE UPDATE ON warning_main_category
FOR EACH ROW
EXECUTE FUNCTION update_warning_main_category_timestamp();

-- 2. Warning Sub Category Table
CREATE TABLE IF NOT EXISTS warning_sub_category (
  id VARCHAR(10) PRIMARY KEY,  -- was1, was2, etc.
  main_category_id VARCHAR(10) NOT NULL REFERENCES warning_main_category(id) ON DELETE CASCADE,
  name_en VARCHAR(255) NOT NULL,
  name_ar VARCHAR(255) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_warning_sub_category_main_id ON warning_sub_category(main_category_id);
CREATE INDEX IF NOT EXISTS idx_warning_sub_category_name_en ON warning_sub_category(name_en);

-- Create auto-update trigger for updated_at
CREATE OR REPLACE FUNCTION update_warning_sub_category_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER warning_sub_category_timestamp_update
BEFORE UPDATE ON warning_sub_category
FOR EACH ROW
EXECUTE FUNCTION update_warning_sub_category_timestamp();

-- 3. Warning Violation Table
CREATE TABLE IF NOT EXISTS warning_violation (
  id VARCHAR(10) PRIMARY KEY,  -- wav1, wav2, etc.
  sub_category_id VARCHAR(10) NOT NULL REFERENCES warning_sub_category(id) ON DELETE CASCADE,
  main_category_id VARCHAR(10) NOT NULL REFERENCES warning_main_category(id) ON DELETE CASCADE,
  name_en VARCHAR(255) NOT NULL,
  name_ar VARCHAR(255) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_warning_violation_sub_id ON warning_violation(sub_category_id);
CREATE INDEX IF NOT EXISTS idx_warning_violation_main_id ON warning_violation(main_category_id);
CREATE INDEX IF NOT EXISTS idx_warning_violation_name_en ON warning_violation(name_en);

-- Create auto-update trigger for updated_at
CREATE OR REPLACE FUNCTION update_warning_violation_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER warning_violation_timestamp_update
BEFORE UPDATE ON warning_violation
FOR EACH ROW
EXECUTE FUNCTION update_warning_violation_timestamp();
