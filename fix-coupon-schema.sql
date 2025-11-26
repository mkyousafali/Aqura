-- Fix Coupon System Schema
-- This script aligns the database schema with the frontend expectations
-- Run this in Supabase SQL Editor

-- 1. First, remove NOT NULL constraint from old column
ALTER TABLE coupon_campaigns 
ALTER COLUMN campaign_name DROP NOT NULL;

-- 2. Add missing columns to coupon_campaigns table
ALTER TABLE coupon_campaigns 
ADD COLUMN IF NOT EXISTS name_en VARCHAR(255),
ADD COLUMN IF NOT EXISTS name_ar VARCHAR(255),
ADD COLUMN IF NOT EXISTS start_date TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS end_date TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS max_claims_per_customer INTEGER DEFAULT 1,
ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'draft';

-- 3. Migrate data from old columns to new columns
UPDATE coupon_campaigns
SET 
  name_en = COALESCE(name_en, campaign_name, 'Untitled'),
  name_ar = COALESCE(name_ar, campaign_name, 'بدون عنوان'),
  start_date = COALESCE(start_date, validity_start_date),
  end_date = COALESCE(end_date, validity_end_date);

-- 4. Make new columns NOT NULL after data migration
ALTER TABLE coupon_campaigns
ALTER COLUMN name_en SET NOT NULL,
ALTER COLUMN name_ar SET NOT NULL,
ALTER COLUMN start_date SET NOT NULL,
ALTER COLUMN end_date SET NOT NULL;

-- 5. Update the check constraint
ALTER TABLE coupon_campaigns DROP CONSTRAINT IF EXISTS valid_campaign_dates;
ALTER TABLE coupon_campaigns 
ADD CONSTRAINT valid_campaign_dates CHECK (end_date > start_date);

-- 6. Drop old columns (optional - uncomment to clean up)
-- ALTER TABLE coupon_campaigns DROP COLUMN IF EXISTS campaign_name;
-- ALTER TABLE coupon_campaigns DROP COLUMN IF EXISTS validity_start_date;
-- ALTER TABLE coupon_campaigns DROP COLUMN IF EXISTS validity_end_date;
-- ALTER TABLE coupon_campaigns DROP COLUMN IF EXISTS description;

-- Verification queries
SELECT 
  column_name, 
  data_type, 
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'coupon_campaigns'
ORDER BY ordinal_position;
