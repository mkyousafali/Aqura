-- Add offer_name column to flyer_offers table
-- This allows users to give custom names to offers in addition to template names

ALTER TABLE public.flyer_offers
ADD COLUMN offer_name text NULL;

-- Add index for searching by offer name
CREATE INDEX IF NOT EXISTS idx_flyer_offers_offer_name 
ON public.flyer_offers 
USING btree (offer_name) 
TABLESPACE pg_default;

-- Add comment
COMMENT ON COLUMN public.flyer_offers.offer_name IS 'Optional custom name for the offer, in addition to the template name';
