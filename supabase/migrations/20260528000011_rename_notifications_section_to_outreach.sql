BEGIN;

UPDATE public.button_main_sections
SET section_name_en = 'Outreach',
    section_name_ar = 'التواصل'
WHERE section_code = 'NOTIFICATIONS';

COMMIT;
