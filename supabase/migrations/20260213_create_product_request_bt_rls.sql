-- Enable RLS on product_request_bt with permissive policies

ALTER TABLE product_request_bt ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all access to product_request_bt" ON product_request_bt;

CREATE POLICY "Allow all access to product_request_bt"
  ON product_request_bt
  FOR ALL
  USING (true)
  WITH CHECK (true);

GRANT ALL ON product_request_bt TO authenticated;
GRANT ALL ON product_request_bt TO service_role;
GRANT ALL ON product_request_bt TO anon;
