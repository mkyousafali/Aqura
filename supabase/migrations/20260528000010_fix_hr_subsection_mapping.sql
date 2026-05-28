BEGIN;

-- Ensure HR subsections exist (safety for older environments)
INSERT INTO public.button_sub_sections (
  main_section_id,
  subsection_code,
  subsection_name_en,
  subsection_name_ar,
  display_order,
  is_active
)
SELECT ms.id, x.subsection_code, x.subsection_name_en, x.subsection_name_ar, x.display_order, true
FROM public.button_main_sections ms
CROSS JOIN (
  VALUES
    ('DASHBOARD', 'Dashboard', 'لوحة التحكم', 1),
    ('MANAGE', 'Manage', 'إدارة', 2),
    ('OPERATIONS', 'Operations', 'العمليات', 3),
    ('REPORTS', 'Reports', 'التقارير', 4)
) AS x(subsection_code, subsection_name_en, subsection_name_ar, display_order)
WHERE ms.section_code = 'HR'
  AND NOT EXISTS (
    SELECT 1
    FROM public.button_sub_sections ss
    WHERE ss.main_section_id = ms.id
      AND ss.subsection_code = x.subsection_code
  );

-- Move SECURITY_CODE to HR Dashboard
UPDATE public.sidebar_buttons b
SET subsection_id = ss_dashboard.id
FROM public.button_main_sections ms
JOIN public.button_sub_sections ss_dashboard
  ON ss_dashboard.main_section_id = ms.id
 AND ss_dashboard.subsection_code = 'DASHBOARD'
WHERE ms.id = b.main_section_id
  AND ms.section_code = 'HR'
  AND b.button_code = 'SECURITY_CODE';

-- Move FINGERPRINT_TRANSACTIONS to HR Reports
UPDATE public.sidebar_buttons b
SET subsection_id = ss_reports.id
FROM public.button_main_sections ms
JOIN public.button_sub_sections ss_reports
  ON ss_reports.main_section_id = ms.id
 AND ss_reports.subsection_code = 'REPORTS'
WHERE ms.id = b.main_section_id
  AND ms.section_code = 'HR'
  AND b.button_code = 'FINGERPRINT_TRANSACTIONS';

COMMIT;
