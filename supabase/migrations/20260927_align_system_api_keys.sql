-- Keep shared Google credentials; only the retired image-search entries are removed.
BEGIN;

DELETE FROM public.system_api_keys
WHERE service_name IN ('google_search_engine_id', 'pixabay');

UPDATE public.system_api_keys
SET description = CASE service_name
  WHEN 'openai' THEN 'OpenAI: flyer design and artwork, text tools, translations, HR warnings, receipt and document analysis.'
  WHEN 'google_gemini' THEN 'Google Gemini: WhatsApp automatic AI replies only.'
  WHEN 'google' THEN 'Google APIs: Maps/Places, Vision OCR, Text-to-Speech and Routes.'
END
WHERE service_name IN ('openai', 'google_gemini', 'google');

COMMIT;
