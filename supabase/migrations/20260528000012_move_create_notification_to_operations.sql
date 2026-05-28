BEGIN;

-- Ensure NOTIFICATIONS OPERATIONS subsection exists
INSERT INTO public.button_sub_sections (
  main_section_id,
  subsection_code,
  subsection_name_en,
  subsection_name_ar,
  display_order,
  is_active
)
SELECT ms.id, 'OPERATIONS', 'Operations', 'العمليات', 3, true
FROM public.button_main_sections ms
WHERE ms.section_code = 'NOTIFICATIONS'
  AND NOT EXISTS (
    SELECT 1
    FROM public.button_sub_sections ss
    WHERE ss.main_section_id = ms.id
      AND ss.subsection_code = 'OPERATIONS'
  );

-- Move CREATE_NOTIFICATION to NOTIFICATIONS -> OPERATIONS
UPDATE public.sidebar_buttons b
SET subsection_id = ss_ops.id
FROM public.button_main_sections ms
JOIN public.button_sub_sections ss_ops
  ON ss_ops.main_section_id = ms.id
 AND ss_ops.subsection_code = 'OPERATIONS'
WHERE b.main_section_id = ms.id
  AND ms.section_code = 'NOTIFICATIONS'
  AND b.button_code = 'CREATE_NOTIFICATION';

COMMIT;
