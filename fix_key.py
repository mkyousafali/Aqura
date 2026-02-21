import sys, os
f = 'supabase/migrations/20260221_create_system_api_keys.sql'
if os.path.exists(f):
    txt = open(f, encoding='utf-8').read()
    if 'REDACTED_GOOGLE_API_KEY' in txt:
        txt = txt.replace('REDACTED_GOOGLE_API_KEY', 'REPLACE_WITH_YOUR_GOOGLE_API_KEY')
        open(f, 'w', encoding='utf-8').write(txt)
