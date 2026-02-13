-- Enable RLS on product_request_po with permissive policies

ALTER TABLE product_request_po ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all access to product_request_po" ON product_request_po;

CREATE POLICY "Allow all access to product_request_po"
  ON product_request_po
  FOR ALL
  USING (true)
  WITH CHECK (true);

GRANT ALL ON product_request_po TO authenticated;
GRANT ALL ON product_request_po TO service_role;
GRANT ALL ON product_request_po TO anon;
