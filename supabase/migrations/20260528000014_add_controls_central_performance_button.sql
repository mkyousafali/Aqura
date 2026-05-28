BEGIN;

-- Ensure CONTROLS -> REPORTS subsection exists
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
WHERE ms.section_code = 'CONTROLS'
  AND NOT EXISTS (
    SELECT 1
    FROM public.button_sub_sections ss
    WHERE ss.main_section_id = ms.id
      AND ss.subsection_code = 'REPORTS'
  );

-- Add permission code for Central Performance under CONTROLS -> REPORTS
INSERT INTO public.sidebar_buttons (
  button_name_en,
  button_name_ar,
  button_code,
  main_section_id,
  subsection_id,
  display_order,
  is_active
)
SELECT
  'Central Performance',
  'الأداء المركزي',
  'CENTRAL_PERFORMANCE',
  ms.id,
  ss.id,
  1,
  true
FROM public.button_main_sections ms
JOIN public.button_sub_sections ss
  ON ss.main_section_id = ms.id
 AND ss.subsection_code = 'REPORTS'
WHERE ms.section_code = 'CONTROLS'
  AND NOT EXISTS (
    SELECT 1 FROM public.sidebar_buttons b WHERE b.button_code = 'CENTRAL_PERFORMANCE'
  );

COMMIT;
