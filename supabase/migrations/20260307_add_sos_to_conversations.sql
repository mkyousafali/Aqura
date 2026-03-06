-- Add SOS flag to wa_conversations
ALTER TABLE public.wa_conversations
ADD COLUMN is_sos boolean DEFAULT false;

-- Create index for querying SOS conversations
CREATE INDEX idx_wa_conversations_sos ON public.wa_conversations(is_sos) WHERE is_sos = true;
