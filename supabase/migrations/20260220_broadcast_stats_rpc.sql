-- RPC Function: Get broadcast statistics for a contact
-- This function aggregates broadcast message stats to reduce client-side queries
-- Contact: phone_number parameter
-- Returns: sent, delivered, read, and failed counts

CREATE OR REPLACE FUNCTION public.get_contact_broadcast_stats(phone_number text)
RETURNS TABLE (
  sent int,
  delivered int,
  read int,
  failed int,
  total int
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    COALESCE(COUNT(*) FILTER (WHERE status = 'sent'), 0) as sent,
    COALESCE(COUNT(*) FILTER (WHERE status = 'delivered'), 0) as delivered,
    COALESCE(COUNT(*) FILTER (WHERE status = 'read'), 0) as read,
    COALESCE(COUNT(*) FILTER (WHERE status = 'failed'), 0) as failed,
    COUNT(*) as total
  FROM wa_broadcast_recipients
  WHERE phone_number = $1;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_contact_broadcast_stats(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_contact_broadcast_stats(text) TO anon;
