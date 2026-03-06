-- Fix corrupted Arabic text in wa_ai_bot_config
-- Clear the corrupted data first
UPDATE public.wa_ai_bot_config 
SET custom_instructions = ''
WHERE custom_instructions LIKE '%???%';

-- Verify the fix
SELECT 
  id,
  substring(custom_instructions, 1, 50) as sample,
  length(custom_instructions) as length
FROM public.wa_ai_bot_config
LIMIT 1;
