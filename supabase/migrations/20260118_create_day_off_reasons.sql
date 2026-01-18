-- Create day_off_reasons table
-- Stores reasons for employee days off with deductibility and documentation requirements

CREATE TABLE IF NOT EXISTS day_off_reasons (
  id VARCHAR(50) PRIMARY KEY,                              -- Short ID format (DRS1, DRS2, etc.)
  reason_en VARCHAR(255) NOT NULL,                         -- Reason in English
  reason_ar VARCHAR(255) NOT NULL,                         -- Reason in Arabic
  is_deductible BOOLEAN DEFAULT false,                     -- Whether this day off is deductible from leave balance
  is_document_mandatory BOOLEAN DEFAULT false,             -- Whether document/proof is mandatory
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(reason_en, reason_ar)                            -- Ensure no duplicate reasons
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_day_off_reasons_deductible ON day_off_reasons(is_deductible);
CREATE INDEX IF NOT EXISTS idx_day_off_reasons_document_mandatory ON day_off_reasons(is_document_mandatory);

-- Create auto-update trigger for updated_at
CREATE OR REPLACE FUNCTION update_day_off_reasons_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER day_off_reasons_timestamp_update
BEFORE UPDATE ON day_off_reasons
FOR EACH ROW
EXECUTE FUNCTION update_day_off_reasons_timestamp();
