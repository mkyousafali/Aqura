-- Create system_api_keys table
-- Stores API keys for external services, manageable from the admin UI

CREATE TABLE IF NOT EXISTS system_api_keys (
  id SERIAL PRIMARY KEY,
  service_name VARCHAR(100) NOT NULL UNIQUE,
  api_key TEXT NOT NULL DEFAULT '',
  description TEXT DEFAULT '',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Index for fast lookup by service name
CREATE INDEX IF NOT EXISTS idx_system_api_keys_service_name ON system_api_keys(service_name);

-- Auto-update trigger for updated_at
CREATE OR REPLACE FUNCTION update_system_api_keys_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER system_api_keys_timestamp_update
BEFORE UPDATE ON system_api_keys
FOR EACH ROW
EXECUTE FUNCTION update_system_api_keys_timestamp();

-- Insert default services (keys must be set via Supabase Studio or admin UI after migration)
INSERT INTO system_api_keys (service_name, api_key, description) VALUES
  ('google', '', 'Google APIs (Maps, Vision, TTS, Gemini) - set key via admin UI'),
  ('pixabay', '', 'Pixabay Image Search API - set key via admin UI'),
  ('google_search_engine_id', '', 'Google Programmable Search Engine ID - set key via admin UI'),
  ('openai', '', 'OpenAI API Key (ChatGPT, Whisper) - set key via admin UI')
ON CONFLICT (service_name) DO NOTHING;
