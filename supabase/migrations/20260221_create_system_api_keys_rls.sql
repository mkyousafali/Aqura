-- RLS for system_api_keys table (master admin only via app logic)

ALTER TABLE system_api_keys ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all access to system_api_keys" ON system_api_keys;

CREATE POLICY "Allow all access to system_api_keys"
  ON system_api_keys
  FOR ALL
  USING (true)
  WITH CHECK (true);

GRANT ALL ON system_api_keys TO authenticated;
GRANT ALL ON system_api_keys TO service_role;
GRANT ALL ON system_api_keys TO anon;

GRANT USAGE, SELECT ON SEQUENCE system_api_keys_id_seq TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE system_api_keys_id_seq TO anon;
GRANT USAGE, SELECT ON SEQUENCE system_api_keys_id_seq TO service_role;
