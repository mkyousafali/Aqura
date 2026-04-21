-- Add configurable minimum bill amount required to spin Gift Wheel
ALTER TABLE public.gift_wheel_settings
ADD COLUMN IF NOT EXISTS minimum_bill_amount numeric NOT NULL DEFAULT 0;

UPDATE public.gift_wheel_settings
SET minimum_bill_amount = 0
WHERE minimum_bill_amount IS NULL;
