-- Check table structure
SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'ai_chat_guide';

-- Check current data
SELECT idx, id, is_enabled FROM public.ai_chat_guide LIMIT 1;
