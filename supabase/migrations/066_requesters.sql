-- Requesters Table Schema
CREATE TABLE IF NOT EXISTS public.requesters (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  requester_id VARCHAR(50) NOT NULL,
  requester_name VARCHAR(255) NOT NULL,
  contact_number VARCHAR(20) NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
  created_by UUID NULL,
  updated_by UUID NULL,
  CONSTRAINT requesters_pkey PRIMARY KEY (id),
  CONSTRAINT requesters_requester_id_key UNIQUE (requester_id)
) TABLESPACE pg_default;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_requesters_name ON public.requesters USING btree (requester_name) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_requesters_requester_id ON public.requesters USING btree (requester_id) TABLESPACE pg_default;

-- Enable Row Level Security
ALTER TABLE public.requesters ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "requesters_authenticated_all" ON public.requesters;
DROP POLICY IF EXISTS "requesters_service_role_all" ON public.requesters;

-- Create RLS policies
CREATE POLICY "requesters_authenticated_all" ON public.requesters
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "requesters_service_role_all" ON public.requesters
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Grant permissions
GRANT ALL ON public.requesters TO authenticated;
GRANT ALL ON public.requesters TO service_role;
GRANT ALL ON public.requesters TO anon;

-- Create trigger for updated_at
CREATE TRIGGER update_requesters_updated_at 
BEFORE UPDATE ON public.requesters 
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();
