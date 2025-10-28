-- Create requesters table for storing requester information
CREATE TABLE IF NOT EXISTS public.requesters (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    requester_id VARCHAR(50) UNIQUE NOT NULL,
    requester_name VARCHAR(255) NOT NULL,
    contact_number VARCHAR(20),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    created_by UUID,
    updated_by UUID
);

-- Drop existing foreign key constraints if they exist
ALTER TABLE public.requesters DROP CONSTRAINT IF EXISTS requesters_created_by_fkey;
ALTER TABLE public.requesters DROP CONSTRAINT IF EXISTS requesters_updated_by_fkey;

-- Create index for efficient searching
CREATE INDEX IF NOT EXISTS idx_requesters_requester_id ON public.requesters(requester_id);
CREATE INDEX IF NOT EXISTS idx_requesters_name ON public.requesters(requester_name);

-- Add comments
COMMENT ON TABLE public.requesters IS 'Table to store requester information for expense requisitions';
COMMENT ON COLUMN public.requesters.requester_id IS 'Unique identifier for the requester (employee ID or custom ID)';
COMMENT ON COLUMN public.requesters.requester_name IS 'Full name of the requester';
COMMENT ON COLUMN public.requesters.contact_number IS 'Contact number of the requester';

-- Enable RLS
ALTER TABLE public.requesters ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
DROP POLICY IF EXISTS "Users can view all requesters" ON public.requesters;
CREATE POLICY "Users can view all requesters" ON public.requesters
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert requesters" ON public.requesters;
CREATE POLICY "Users can insert requesters" ON public.requesters
    FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Users can update requesters" ON public.requesters;
CREATE POLICY "Users can update requesters" ON public.requesters
    FOR UPDATE USING (true);

-- Add trigger for updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc', NOW());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_requesters_updated_at ON public.requesters;
CREATE TRIGGER update_requesters_updated_at
    BEFORE UPDATE ON public.requesters
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Add foreign key to expense_requisitions table to reference requesters
ALTER TABLE public.expense_requisitions 
ADD COLUMN IF NOT EXISTS requester_ref_id UUID REFERENCES public.requesters(id);

-- Create index for the new foreign key
CREATE INDEX IF NOT EXISTS idx_expense_requisitions_requester_ref ON public.expense_requisitions(requester_ref_id);

-- Migrate existing data: try to match existing requester_id and requester_name with the new requesters table
-- This is a best-effort migration - manual review might be needed
UPDATE public.expense_requisitions 
SET requester_ref_id = r.id
FROM public.requesters r
WHERE expense_requisitions.requester_id = r.requester_id
  AND expense_requisitions.requester_ref_id IS NULL;

-- Add comment to the new foreign key column
COMMENT ON COLUMN public.expense_requisitions.requester_ref_id IS 'Reference to the requesters table for normalized requester data';