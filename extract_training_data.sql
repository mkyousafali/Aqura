-- Extract AI Bot Training Data
SELECT 
  'ID: ' || id::text as section,
  'ID: ' || id::text as value
FROM wa_ai_bot_config
UNION ALL
SELECT 'Enabled', is_enabled::text FROM wa_ai_bot_config LIMIT 1
UNION ALL
SELECT 'Tone', tone FROM wa_ai_bot_config LIMIT 1
UNION ALL
SELECT 'Default Language', default_language FROM wa_ai_bot_config LIMIT 1
UNION ALL
SELECT 'Max Replies per Conversation', max_replies_per_conversation::text FROM wa_ai_bot_config LIMIT 1
UNION ALL
SELECT 'Custom Instructions', custom_instructions FROM wa_ai_bot_config LIMIT 1
UNION ALL
SELECT 'Bot Rules', bot_rules FROM wa_ai_bot_config LIMIT 1;
