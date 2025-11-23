-- =====================================================
-- Flyer Master: Offers Table
-- Created: 2025-11-23
-- Description: Creates flyer_offers table for flyer offer campaigns
-- =====================================================

-- Create flyer_offers table
CREATE TABLE IF NOT EXISTS public.flyer_offers (
    -- Primary Key
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    
    -- Offer Identification
    template_id TEXT NOT NULL DEFAULT (gen_random_uuid())::text UNIQUE,
    template_name TEXT NOT NULL,
    
    -- Offer Dates
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    
    -- Status
    is_active BOOLEAN NOT NULL DEFAULT true,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
    
    -- Constraints
    CONSTRAINT flyer_offers_pkey PRIMARY KEY (id),
    CONSTRAINT flyer_offers_template_id_key UNIQUE (template_id),
    CONSTRAINT flyer_offers_dates_check CHECK (end_date >= start_date)
) TABLESPACE pg_default;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_flyer_offers_is_active 
    ON public.flyer_offers USING btree (is_active) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_flyer_offers_dates 
    ON public.flyer_offers USING btree (start_date, end_date) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_flyer_offers_template_id 
    ON public.flyer_offers USING btree (template_id) 
    TABLESPACE pg_default;

-- Add trigger for auto-updating updated_at
CREATE TRIGGER update_flyer_offers_updated_at
    BEFORE UPDATE ON public.flyer_offers
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Add comments
COMMENT ON TABLE public.flyer_offers IS 'Stores flyer offer campaigns and templates';
COMMENT ON COLUMN public.flyer_offers.template_id IS 'Unique template identifier for the offer';
COMMENT ON COLUMN public.flyer_offers.template_name IS 'Display name for the offer template';
COMMENT ON COLUMN public.flyer_offers.is_active IS 'Whether this offer is currently active';
COMMENT ON CONSTRAINT flyer_offers_dates_check ON public.flyer_offers IS 'Ensures end date is not before start date';
