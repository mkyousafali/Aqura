BEGIN;

INSERT INTO public.button_sub_sections (
  main_section_id,
  subsection_code,
  subsection_name_en,
  subsection_name_ar,
  display_order,
  is_active
)
SELECT ms.id, 'DASHBOARD', 'Dashboard', 'لوحة التحكم', 1, true
FROM public.button_main_sections ms
WHERE ms.section_code = 'CONTROLS'
  AND NOT EXISTS (
    SELECT 1
    FROM public.button_sub_sections ss
    WHERE ss.main_section_id = ms.id
      AND ss.subsection_code = 'DASHBOARD'
  );

COMMIT;
