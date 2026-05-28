BEGIN;

INSERT INTO public.button_sub_sections (
  main_section_id,
  subsection_code,
  subsection_name_en,
  subsection_name_ar,
  display_order,
  is_active
)
SELECT ms.id, 'REPORTS', 'Reports', 'التقارير', 4, true
FROM public.button_main_sections ms
WHERE ms.section_code = 'NOTIFICATIONS'
  AND NOT EXISTS (
    SELECT 1
    FROM public.button_sub_sections ss
    WHERE ss.main_section_id = ms.id
      AND ss.subsection_code = 'REPORTS'
  );

COMMIT;
