-- Migration for table: requesters
-- Generated on: 2025-10-30T21:55:45.297Z

CREATE TABLE IF NOT EXISTS public.requesters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
    requester_id VARCHAR(255) NOT NULL,
    requester_name VARCHAR(255) NOT NULL,
    contact_number VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    created_by UUID NOT NULL,
    updated_by JSONB
);

CREATE INDEX IF NOT EXISTS idx_requesters_created_at ON public.requesters(created_at);
CREATE INDEX IF NOT EXISTS idx_requesters_updated_at ON public.requesters(updated_at);

-- Enable Row Level Security
ALTER TABLE public.requesters ENABLE ROW LEVEL SECURITY;

-- Add updated_at trigger
CREATE TRIGGER set_requesters_updated_at
    BEFORE UPDATE ON public.requesters
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();

-- Table comments
COMMENT ON TABLE public.requesters IS 'Generated from Aqura schema analysis';
