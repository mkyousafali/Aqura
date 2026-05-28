BEGIN;

-- Ensure Delivery -> Manage subsection exists
INSERT INTO public.button_sub_sections (
  main_section_id,
  subsection_code,
  subsection_name_en,
  subsection_name_ar,
  display_order,
  is_active
)
SELECT ms.id, 'MANAGE', 'Manage', 'إدارة', 2, true
FROM public.button_main_sections ms
WHERE ms.section_code = 'DELIVERY'
  AND NOT EXISTS (
    SELECT 1
    FROM public.button_sub_sections ss
    WHERE ss.main_section_id = ms.id
      AND ss.subsection_code = 'MANAGE'
  );

-- Insert unique code for Delivery Manage Products
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
  'Manage Products',
  'إدارة المنتجات',
  'DELIVERY_MANAGE_PRODUCTS',
  ms.id,
  ss.id,
  4,
  true
FROM public.button_main_sections ms
JOIN public.button_sub_sections ss
  ON ss.main_section_id = ms.id
WHERE ms.section_code = 'DELIVERY'
  AND ss.subsection_code = 'MANAGE'
  AND NOT EXISTS (
    SELECT 1 FROM public.sidebar_buttons b WHERE b.button_code = 'DELIVERY_MANAGE_PRODUCTS'
  );

-- Copy user-level permissions from PRODUCTS_MANAGER to DELIVERY_MANAGE_PRODUCTS
INSERT INTO public.button_permissions (user_id, button_id, is_enabled)
SELECT
  bp.user_id,
  new_btn.id,
  bp.is_enabled
FROM public.button_permissions bp
JOIN public.sidebar_buttons old_btn
  ON old_btn.id = bp.button_id
JOIN public.users u
  ON u.id = bp.user_id
JOIN public.sidebar_buttons new_btn
  ON new_btn.button_code = 'DELIVERY_MANAGE_PRODUCTS'
WHERE old_btn.button_code = 'PRODUCTS_MANAGER'
  AND NOT EXISTS (
    SELECT 1
    FROM public.button_permissions bp2
    WHERE bp2.user_id = bp.user_id
      AND bp2.button_id = new_btn.id
  );

COMMIT;
