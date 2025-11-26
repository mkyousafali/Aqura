-- Fix Coupon System Schema - Final Version
-- This script adds the correct columns for bilingual names and date-only fields
-- Run this in Supabase SQL Editor

-- 1. Drop NOT NULL constraints from old columns
ALTER TABLE coupon_campaigns 
ALTER COLUMN campaign_name DROP NOT NULL,
ALTER COLUMN validity_start_date DROP NOT NULL,
ALTER COLUMN validity_end_date DROP NOT NULL;

-- 2. Add new columns
ALTER TABLE coupon_campaigns 
ADD COLUMN IF NOT EXISTS name_en VARCHAR(255),
ADD COLUMN IF NOT EXISTS name_ar VARCHAR(255),
ADD COLUMN IF NOT EXISTS start_date DATE,
ADD COLUMN IF NOT EXISTS end_date DATE,
ADD COLUMN IF NOT EXISTS max_claims_per_customer INTEGER DEFAULT 1;

-- 3. Migrate existing data (if any)
UPDATE coupon_campaigns
SET 
  name_en = COALESCE(name_en, campaign_name, 'Untitled'),
  name_ar = COALESCE(name_ar, campaign_name, 'بدون عنوان'),
  start_date = COALESCE(start_date, DATE(validity_start_date)),
  end_date = COALESCE(end_date, DATE(validity_end_date))
WHERE name_en IS NULL OR name_ar IS NULL OR start_date IS NULL OR end_date IS NULL;

-- 4. Make new columns NOT NULL
ALTER TABLE coupon_campaigns
ALTER COLUMN name_en SET NOT NULL,
ALTER COLUMN name_ar SET NOT NULL,
ALTER COLUMN start_date SET NOT NULL,
ALTER COLUMN end_date SET NOT NULL;

-- 5. Update the check constraint for dates
ALTER TABLE coupon_campaigns DROP CONSTRAINT IF EXISTS valid_campaign_dates;
ALTER TABLE coupon_campaigns 
ADD CONSTRAINT valid_campaign_dates CHECK (end_date > start_date);

-- 6. Optional: Drop old columns (uncomment to clean up)
-- ALTER TABLE coupon_campaigns DROP COLUMN IF EXISTS campaign_name;
-- ALTER TABLE coupon_campaigns DROP COLUMN IF EXISTS validity_start_date;
-- ALTER TABLE coupon_campaigns DROP COLUMN IF EXISTS validity_end_date;
-- ALTER TABLE coupon_campaigns DROP COLUMN IF EXISTS description;

-- Verification query
SELECT 
  column_name, 
  data_type, 
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'coupon_campaigns'
ORDER BY ordinal_position;
