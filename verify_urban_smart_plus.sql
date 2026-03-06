-- Verify the Urban Smart Plus bot configuration was deployed correctly
SELECT 
  id,
  is_enabled,
  substring(bot_rules, 1, 100) as bot_rules_sample,
  substring(custom_instructions, 1, 100) as instructions_sample,
  jsonb_array_length(training_qa) as qa_pair_count,
  human_support_enabled,
  human_support_start_time,
  human_support_end_time,
  updated_at
FROM public.wa_ai_bot_config
WHERE id = '00000000-0000-0000-0000-000000000001';
