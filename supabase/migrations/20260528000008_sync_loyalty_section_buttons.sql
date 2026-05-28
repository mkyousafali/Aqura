BEGIN;

-- Ensure LOYALTY main section exists
INSERT INTO public.button_main_sections (section_code, section_name_en, section_name_ar, display_order, is_active)
SELECT 'LOYALTY', 'Loyalty', 'الولاء',
       COALESCE((SELECT MAX(display_order) + 1 FROM public.button_main_sections), 1),
       true
WHERE NOT EXISTS (
  SELECT 1 FROM public.button_main_sections WHERE section_code = 'LOYALTY'
);

-- Ensure required LOYALTY subsections exist
INSERT INTO public.button_sub_sections (main_section_id, subsection_code, subsection_name_en, subsection_name_ar, display_order, is_active)
SELECT ms.id, x.subsection_code, x.subsection_name_en, x.subsection_name_ar,
       ROW_NUMBER() OVER (ORDER BY x.subsection_code),
       true
FROM public.button_main_sections ms
CROSS JOIN (
  VALUES
    ('DASHBOARD', 'Dashboard', 'لوحة التحكم'),
    ('MANAGE', 'Manage', 'إدارة')
) AS x(subsection_code, subsection_name_en, subsection_name_ar)
WHERE ms.section_code = 'LOYALTY'
  AND NOT EXISTS (
    SELECT 1
    FROM public.button_sub_sections ss
    WHERE ss.main_section_id = ms.id
      AND ss.subsection_code = x.subsection_code
  );

-- Ensure LOYALTY_DASHBOARD and MANAGE_TIERS button codes exist
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
  x.button_name_en,
  x.button_name_ar,
  x.button_code,
  ms.id,
  ss.id,
  x.display_order,
  true
FROM public.button_main_sections ms
JOIN public.button_sub_sections ss
  ON ss.main_section_id = ms.id
JOIN (
  VALUES
    ('LOYALTY_DASHBOARD', 'Loyalty Program', 'برنامج الولاء', 'DASHBOARD', 1),
    ('MANAGE_TIERS', 'Manage Tiers', 'إدارة المستويات', 'MANAGE', 1)
) AS x(button_code, button_name_en, button_name_ar, subsection_code, display_order)
  ON x.subsection_code = ss.subsection_code
WHERE ms.section_code = 'LOYALTY'
  AND NOT EXISTS (
    SELECT 1 FROM public.sidebar_buttons b WHERE b.button_code = x.button_code
  );

COMMIT;
