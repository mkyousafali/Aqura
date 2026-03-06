-- Check wa_ai_bot_config table structure
SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'wa_ai_bot_config' ORDER BY ordinal_position;

-- Display current config
SELECT id, is_enabled, tone, bot_rules FROM public.wa_ai_bot_config LIMIT 1;
