-- Create RPC functions for incrementing view counts

-- Drop old functions if they exist
DROP FUNCTION IF EXISTS increment_view_button_count(INTEGER);
DROP FUNCTION IF EXISTS increment_page_visit_count(INTEGER);

-- Increment view button count
CREATE OR REPLACE FUNCTION increment_view_button_count(offer_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE view_offer
  SET view_button_count = view_button_count + 1
  WHERE id = offer_id;
END;
$$ LANGUAGE plpgsql;

-- Increment page visit count
CREATE OR REPLACE FUNCTION increment_page_visit_count(offer_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE view_offer
  SET page_visit_count = page_visit_count + 1
  WHERE id = offer_id;
END;
$$ LANGUAGE plpgsql;

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION increment_view_button_count(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_page_visit_count(UUID) TO authenticated;
