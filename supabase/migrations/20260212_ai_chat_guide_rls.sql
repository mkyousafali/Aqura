-- Enable RLS on ai_chat_guide with permissive policies

ALTER TABLE ai_chat_guide ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all access to ai_chat_guide" ON ai_chat_guide;

CREATE POLICY "Allow all access to ai_chat_guide"
  ON ai_chat_guide
  FOR ALL
  USING (true)
  WITH CHECK (true);

GRANT ALL ON ai_chat_guide TO authenticated;
GRANT ALL ON ai_chat_guide TO service_role;
GRANT ALL ON ai_chat_guide TO anon;

-- Grant sequence usage for SERIAL id
GRANT USAGE, SELECT ON SEQUENCE ai_chat_guide_id_seq TO anon;
GRANT USAGE, SELECT ON SEQUENCE ai_chat_guide_id_seq TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE ai_chat_guide_id_seq TO service_role;
