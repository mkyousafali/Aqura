-- Add description column to day_off table
ALTER TABLE public.day_off
ADD COLUMN description TEXT DEFAULT NULL;

-- Add index for faster queries
CREATE INDEX idx_day_off_description ON public.day_off(description);

-- Comment on column
COMMENT ON COLUMN public.day_off.description IS 'Description or reason for the day off request';
