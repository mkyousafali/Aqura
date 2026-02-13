-- Enable RLS on product_request_st with permissive policies

ALTER TABLE product_request_st ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all access to product_request_st" ON product_request_st;

CREATE POLICY "Allow all access to product_request_st"
  ON product_request_st
  FOR ALL
  USING (true)
  WITH CHECK (true);

GRANT ALL ON product_request_st TO authenticated;
GRANT ALL ON product_request_st TO service_role;
GRANT ALL ON product_request_st TO anon;
